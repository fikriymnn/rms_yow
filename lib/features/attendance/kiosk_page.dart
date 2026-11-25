import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'attendance_models.dart';
import 'attendance_queue.dart';
import 'consent.dart';
import 'face_check_page.dart';
import 'location_service.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

const _maxAccuracyM = 80;
const _toleranceM = 10;

/// Daftar karyawan outlet kiosk (dari server).
final kioskStaffProvider = FutureProvider.autoDispose<List<KioskStaff>>((
  ref,
) async {
  final outletId = ref.watch(activeOutletIdProvider);
  final raw =
      await ref
              .read(apiClientProvider)
              .get(
                '/attendance/kiosk/staff',
                query: {if (outletId != null) 'outlet_id': outletId},
              )
          as List<dynamic>;
  return [for (final m in raw) KioskStaff.fromJson(m as Map<String, dynamic>)];
});

/// Absen bersama: pilih nama, masukkan PIN, lalu absen.
/// Akun role Absen bersama: layar penuh ([embedded] false, ada tombol Keluar).
/// Owner: salah satu menu di aplikasi ([embedded] true), memakai outlet yang sedang aktif.
class KioskPage extends ConsumerStatefulWidget {
  const KioskPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends ConsumerState<KioskPage>
    with WidgetsBindingObserver {
  StreamSubscription<LocationFix>? _sub;
  Timer? _tick;
  LocationFix? _fix;
  LocationException? _locError;
  bool _busy = false;
  String _query = '';
  static final _hm = DateFormat('HH:mm');
  static final _day = DateFormat('EEEE, d MMMM');

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    _startLocation();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
      _flush();
    });
    Future.microtask(_flush);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flush();
      ref.invalidate(kioskStaffProvider);
    }
  }

  Future<void> _flush() async {
    final n = await ref.read(attendanceQueueProvider).flush();
    if (n > 0 && mounted) ref.invalidate(kioskStaffProvider);
  }

  Future<void> _startLocation() async {
    try {
      await ensureLocationReady();
      await _sub?.cancel();
      _sub = watchLocation().listen((f) {
        if (mounted) setState(() => _fix = f);
      }, onError: (_) {});
      currentFix()
          .then((f) {
            if (mounted && _fix == null) setState(() => _fix = f);
          })
          .catchError((_) {});
      if (mounted) setState(() => _locError = null);
    } on LocationException catch (e) {
      if (mounted) setState(() => _locError = e);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  /// Alasan perangkat belum boleh dipakai absen (null = lokasi memenuhi syarat).
  String? _blocker() {
    final outlet = ref.read(activeOutletProvider);
    final fix = _fix;
    if (outlet == null) return 'Pilih outlet terlebih dahulu.';
    if (outlet.lat == null || outlet.lng == null) {
      return 'Lokasi outlet belum diatur. Minta owner mengaturnya di Kelola outlet.';
    }
    if (_locError != null) return _locError!.message;
    if (fix == null) return 'Mencari sinyal GPS...';
    if (fix.mocked) {
      return 'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi lokasi palsu.';
    }
    if (fix.accuracy > _maxAccuracyM) {
      return 'Akurasi GPS kurang (±${fix.accuracy.round()} m). Pindahkan tablet ke tempat terbuka.';
    }
    final d = Geolocator.distanceBetween(
      fix.lat,
      fix.lng,
      outlet.lat!,
      outlet.lng!,
    );
    if (d > outlet.radiusM + _toleranceM) {
      return 'Tablet di luar area outlet (±${d.round()} m, batas ${outlet.radiusM} m).';
    }
    return null;
  }

  Future<void> _start(KioskStaff s) async {
    if (_busy) return;
    if (!s.hasPin) {
      _toast('PIN ${s.name} belum diatur. Minta manager mengaturnya.');
      return;
    }
    final block = _blocker();
    if (block != null) {
      _toast(block);
      return;
    }
    final eventId = const Uuid().v4(); // terikat ke tiket PIN
    final ticket = await showAppDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(
        name: s.name,
        verify: (pin) async {
          final m =
              await ref
                      .read(apiClientProvider)
                      .post(
                        '/attendance/kiosk/verify',
                        data: {
                          'user_id': s.id,
                          'pin': pin,
                          'event_id': eventId,
                          'outlet_id': ?ref.read(activeOutletIdProvider),
                        },
                      )
                  as Map<String, dynamic>;
          return m['ticket'] as String;
        },
      ),
    );
    if (ticket == null || !mounted) return;

    setState(() => _busy = true);
    try {
      if (!s.consentOk) {
        if (!await askConsentAgreement(context, forName: s.name)) return;
        await ref
            .read(apiClientProvider)
            .post(
              '/attendance/kiosk/consent',
              data: {
                'user_id': s.id,
                'ticket': ticket,
                'version': kConsentVersion,
                'outlet_id': ?ref.read(activeOutletIdProvider),
              },
            );
      }
      if (!mounted) return;
      final jpeg = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => const FaceCheckPage()),
      );
      if (jpeg == null) return;

      final fix = _fix;
      if (fix == null || _blocker() != null) {
        _toast('Lokasi tidak lagi memenuhi syarat. Coba lagi.');
        return;
      }
      // arah absen: hormati catatan karyawan ini yang masih menunggu dikirim
      var open = s.clockedIn;
      final queued = [
        for (final q
            in ref.read(queueItemsProvider).value ?? const <QueueItem>[])
          if (q.userId == s.id && q.status == 'pending') q,
      ];
      for (final q in queued) {
        open = q.kind == 'in';
      }
      final kind = open ? 'out' : 'in';

      final queue = ref.read(attendanceQueueProvider);
      await queue.enqueue(
        QueueItem(
          eventId: eventId,
          kind: kind,
          clientTime: DateTime.now().millisecondsSinceEpoch,
          lat: fix.lat,
          lng: fix.lng,
          accuracy: fix.accuracy,
          mocked: fix.mocked,
          liveness: true,
          photoB64: base64Encode(jpeg),
          userId: s.id,
          userName: s.name,
          ticket: ticket,
          outletId: ref.read(activeOutletIdProvider),
        ),
      );
      final done = await queue.flushWithResults();
      ref.invalidate(kioskStaffProvider);
      await _showResult(s.name, kind, done[eventId]);
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hasil absen untuk karyawan di tablet bersama; menutup sendiri setelah 5 detik.
  Future<void> _showResult(
    String name,
    String kind,
    AttendanceRecord? rec,
  ) async {
    if (!mounted) return;
    final label = kind == 'in' ? 'masuk' : 'pulang';
    final note = rec == null ? null : punctualityText(rec, out: kind == 'out');
    final warn =
        rec == null ||
        (kind == 'in' ? rec.inStatus == 'late' : rec.outStatus == 'early');
    final c = toneColors(warn ? Tone.warning : Tone.success);
    final timer = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          rec == null
              ? Icons.cloud_upload_outlined
              : Icons.check_circle_outline,
          size: 48,
          color: c.fg,
        ),
        title: Text(name, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rec == null
                  ? 'Absen $label disimpan. Akan dikirim otomatis saat online.'
                  : 'Absen $label tercatat',
              textAlign: TextAlign.center,
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: c.fg,
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    timer.cancel();
  }

  Future<void> _logout(int pending) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun kiosk?'),
        content: Text(
          pending > 0
              ? '$pending absen belum terkirim. Jika keluar sekarang, antrean tetap '
                    'tersimpan di tablet ini dan terkirim saat akun kiosk login lagi.'
              : 'Tablet tidak bisa dipakai absen sampai akun kiosk login lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(sessionProvider.notifier).logout();
  }

  Widget _banner(IconData icon, String text, Tone tone, {Widget? trailing}) {
    final c = toneColors(tone);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: c.fg),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _tile(KioskStaff s) {
    final initial = s.name.trim().isEmpty
        ? '?'
        : s.name.trim()[0].toUpperCase();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : () => _start(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      s.position.isNotEmpty ? s.position : s.roleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!s.hasPin)
                const StatusPill('PIN belum diatur', tone: Tone.danger)
              else if (s.clockedIn)
                const StatusPill('Sedang bekerja', tone: Tone.success)
              else
                const StatusPill('Belum masuk'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: RmsAppBar(title: const Text('Absensi')),
        body: const EmptyState(
          icon: Icons.tablet_android,
          title: 'Kiosk absensi hanya tersedia di aplikasi Android',
        ),
      );
    }
    final outlet = ref.watch(activeOutletProvider);
    final staff = ref.watch(kioskStaffProvider);
    final queue = ref.watch(queueItemsProvider).value ?? <QueueItem>[];
    final pending = queue.where((q) => q.status == 'pending').length;
    final rejected = queue.where((q) => q.status == 'rejected').toList();
    final block = _blocker();
    final now = DateTime.now();

    return Scaffold(
      appBar: RmsAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.embedded ? 'Absen bersama' : 'Absensi karyawan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (outlet != null)
              Text(
                outlet.name,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reload') ref.invalidate(kioskStaffProvider);
              if (v == 'logout') _logout(pending);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reload', child: Text('Muat ulang daftar')),
              if (!widget.embedded)
                const PopupMenuItem(value: 'logout', child: Text('Keluar akun kiosk')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [AppColors.ink, AppColors.inkSoft],
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _hm.format(now),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${_day.format(now)}\nPilih nama Anda untuk absen',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (block != null)
              _banner(Icons.location_off_outlined, block, Tone.danger),
            if (pending > 0)
              _banner(
                Icons.cloud_upload_outlined,
                '$pending absen menunggu dikirim (otomatis saat online)',
                Tone.warning,
              ),
            for (final q in rejected)
              _banner(
                Icons.error_outline,
                '${q.userName.isEmpty ? 'Absen' : q.userName} ditolak: ${q.error}',
                Tone.danger,
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(attendanceQueueProvider).dismiss(q.eventId),
                  child: const Text('Hapus'),
                ),
              ),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari nama',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: staff.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorText(e), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => ref.invalidate(kioskStaffProvider),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
                data: (list) {
                  final shown = [
                    for (final s in list)
                      if (_query.isEmpty ||
                          s.name.toLowerCase().contains(_query))
                        s,
                  ];
                  if (shown.isEmpty) {
                    return const EmptyState(
                      icon: Icons.group_outlined,
                      title: 'Tidak ada karyawan',
                      message:
                          'Belum ada karyawan yang boleh absen di outlet ini',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(kioskStaffProvider.future),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisExtent: 72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _tile(shown[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog PIN. Memverifikasi ke server di dalam dialog agar PIN salah bisa dicoba lagi.
class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.name, required this.verify});
  final String name;
  final Future<String> Function(String pin) verify;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _c.text.length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ticket = await widget.verify(_c.text);
      if (mounted) Navigator.pop(context, ticket);
    } catch (e) {
      if (!mounted) return;
      _c.clear();
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Halo, ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Masukkan PIN absensi Anda'),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            obscureText: true,
            enabled: !_busy,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(errorText: _error, counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: (_busy || _c.text.length < 4) ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lanjut'),
        ),
      ],
    );
  }
}
