import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'attendance_models.dart';
import 'attendance_queue.dart';
import 'consent.dart';
import 'face_check_page.dart';
import 'location_service.dart';

const _maxAccuracyM = 80;
const _toleranceM = 10;

class ClockPage extends ConsumerStatefulWidget {
  const ClockPage({super.key});
  @override
  ConsumerState<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends ConsumerState<ClockPage> {
  StreamSubscription<LocationFix>? _sub;
  Timer? _tick;
  LocationFix? _fix;
  LocationException? _locError;
  bool _busy = false;
  static final _hm = DateFormat('HH:mm');
  static final _day = DateFormat('EEE, d MMM');

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _startLocation();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    Future.microtask(() => ref.read(attendanceMeProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
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

  ({double? distance, bool inArea}) _areaStatus() {
    final outlet = ref.read(sessionProvider).value?.outlet;
    final fix = _fix;
    if (fix == null || outlet?.lat == null || outlet?.lng == null) {
      return (distance: null, inArea: false);
    }
    final d = Geolocator.distanceBetween(
      fix.lat,
      fix.lng,
      outlet!.lat!,
      outlet.lng!,
    );
    return (distance: d, inArea: d <= outlet.radiusM + _toleranceM);
  }

  Future<void> _clock(String kind) async {
    setState(() => _busy = true);
    try {
      if (!await ensureConsent(context, ref)) return;
      final jpeg = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => const FaceCheckPage()),
      );
      if (jpeg == null) return;

      // periksa lagi lokasi terbaru setelah verifikasi wajah
      final fix = _fix;
      final area = _areaStatus();
      if (fix == null ||
          !area.inArea ||
          fix.accuracy > _maxAccuracyM ||
          fix.mocked) {
        _toast('Lokasi tidak lagi memenuhi syarat. Coba lagi.');
        return;
      }
      final queue = ref.read(attendanceQueueProvider);
      await queue.enqueue(
        QueueItem(
          eventId: const Uuid().v4(),
          kind: kind,
          clientTime: DateTime.now().millisecondsSinceEpoch,
          lat: fix.lat,
          lng: fix.lng,
          accuracy: fix.accuracy,
          mocked: fix.mocked,
          liveness: true,
          photoB64: base64Encode(jpeg),
        ),
      );
      final sent = await queue.flush();
      final label = kind == 'in' ? 'masuk' : 'pulang';
      _toast(
        sent > 0
            ? 'Absen $label tercatat'
            : 'Absen $label disimpan. Akan dikirim otomatis saat online.',
      );
    } catch (e) {
      _toast('Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _banner(
    IconData icon,
    String text,
    Color bg,
    Color fg, {
    Widget? trailing,
  }) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: GoogleFonts.inter(fontSize: 13, color: fg)),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Absensi')),
        body: const EmptyState(
          icon: Icons.phone_android,
          title: 'Absensi hanya tersedia di aplikasi Android',
        ),
      );
    }
    final session = ref.watch(sessionProvider).value;
    final outlet = session?.outlet;
    final me = ref.watch(attendanceMeProvider).value;
    final queue = ref.watch(queueItemsProvider).value ?? <QueueItem>[];
    final now = DateTime.now();

    final pending = queue.where((q) => q.status == 'pending').toList();
    final rejected = queue.where((q) => q.status == 'rejected').toList();
    var isOpen = me?.open != null;
    for (final q in pending) {
      isOpen = q.kind == 'in';
    }
    final kind = isOpen ? 'out' : 'in';

    final area = _areaStatus();
    final fix = _fix;
    final hasOutletLoc = outlet?.lat != null && outlet?.lng != null;
    final accuracyOk = fix != null && fix.accuracy <= _maxAccuracyM;
    final mocked = fix?.mocked ?? false;
    final canClock =
        !_busy && hasOutletLoc && area.inArea && accuracyOk && !mocked;

    String locText;
    Tone locTone = Tone.info;
    if (outlet == null) {
      locText = 'Akun ini tidak terikat outlet.';
      locTone = Tone.neutral;
    } else if (!hasOutletLoc) {
      locText =
          'Lokasi outlet belum diatur. Minta owner mengaturnya di Kelola outlet.';
      locTone = Tone.danger;
    } else if (_locError != null) {
      locText = _locError!.message;
      locTone = Tone.danger;
    } else if (fix == null) {
      locText = 'Mencari sinyal GPS...';
      locTone = Tone.neutral;
    } else if (mocked) {
      locText =
          'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi lokasi palsu.';
      locTone = Tone.danger;
    } else if (!accuracyOk) {
      locText =
          'Akurasi GPS kurang (±${fix.accuracy.round()} m). Pindah ke tempat terbuka.';
      locTone = Tone.danger;
    } else if (area.inArea) {
      locText = 'Dalam area outlet (±${area.distance!.round()} m dari titik)';
      locTone = Tone.success;
    } else {
      locText =
          'Di luar area outlet (±${area.distance!.round()} m, batas ${outlet!.radiusM} m)';
      locTone = Tone.danger;
    }
    final locColors = toneColors(locTone);

    String statusText;
    final open = me?.open;
    if (pending.isNotEmpty && pending.last.kind == 'in' && open == null) {
      statusText = 'Sedang bekerja (absen masuk menunggu dikirim)';
    } else if (open != null && isOpen) {
      final mins = ((now.millisecondsSinceEpoch - open.clockInAt) / 60000)
          .round();
      statusText =
          'Sedang bekerja sejak ${_hm.format(DateTime.fromMillisecondsSinceEpoch(open.clockInAt))} • ${durationText(mins)}';
    } else {
      statusText = isOpen ? 'Sedang bekerja' : 'Belum absen masuk';
    }

    final staleRecords = (me?.recent ?? const <AttendanceRecord>[]).where(
      (r) => r.stale,
    );

    final hero = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.inkSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            _hm.format(now),
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_day.format(now)} • ${outlet?.name ?? '-'}',
            style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOpen ? const Color(0xFF6EE7B7) : Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final locationCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: locColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              locTone == Tone.success
                  ? Icons.check_circle_outline
                  : Icons.place_outlined,
              color: locColors.fg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locText,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: locColors.fg,
                  ),
                ),
                if (fix != null)
                  Text(
                    'Akurasi GPS ±${fix.accuracy.round()} m',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (_locError?.openSettings ?? false)
            TextButton(
              onPressed: Geolocator.openAppSettings,
              child: const Text('Pengaturan'),
            ),
        ],
      ),
    );

    final button = SizedBox(
      height: 60,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: isOpen ? AppColors.rose : AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: canClock ? () => _clock(kind) : null,
        icon: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(isOpen ? Icons.logout : Icons.login),
        label: Text(isOpen ? 'Absen pulang' : 'Absen masuk'),
      ),
    );

    final alerts = Column(
      children: [
        if (pending.isNotEmpty)
          _banner(
            Icons.schedule_send,
            '${pending.length} absen menunggu dikirim ke server',
            const Color(0xFFFEF3C7),
            const Color(0xFF92400E),
          ),
        for (final q in rejected)
          _banner(
            Icons.cancel_outlined,
            'Absen ${q.kind == 'in' ? 'masuk' : 'pulang'} '
            '${_hm.format(DateTime.fromMillisecondsSinceEpoch(q.clientTime))} ditolak: ${q.error}',
            AppColors.roseSoft,
            const Color(0xFF9F1239),
            trailing: IconButton(
              tooltip: 'Tutup',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(attendanceQueueProvider).dismiss(q.eventId),
            ),
          ),
        for (final r in staleRecords)
          _banner(
            Icons.warning_amber,
            'Lupa absen pulang (${_day.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt))}). '
            'Hubungi manager untuk mengoreksi jam pulang.',
            AppColors.roseSoft,
            const Color(0xFF9F1239),
          ),
      ],
    );

    final history = SectionCard(
      title: '14 hari terakhir',
      child: (me == null || me.recent.isEmpty)
          ? const EmptyState(icon: Icons.history, title: 'Belum ada catatan')
          : Column(
              children: [
                for (final r in me.recent)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('d').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    r.clockInAt,
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                DateFormat('MMM').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    r.clockInAt,
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_hm.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt))} - '
                                '${r.clockOutAt == null ? '...' : _hm.format(DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!))}'
                                '${r.minutes == null ? '' : '  •  ${durationText(r.minutes!)}'}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (r.edited)
                                    const StatusPill(
                                      'Dikoreksi',
                                      tone: Tone.info,
                                    ),
                                  if (r.inFlags.contains('late_sync'))
                                    const StatusPill(
                                      'Dikirim terlambat',
                                      tone: Tone.warning,
                                    ),
                                  if (r.reviewStatus == 'suspicious')
                                    const StatusPill(
                                      'Ditandai manager',
                                      tone: Tone.danger,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi'),
        actions: [
          IconButton(
            tooltip: 'Segarkan lokasi',
            icon: const Icon(Icons.my_location),
            onPressed: _startLocation,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hero,
              const SizedBox(height: 12),
              locationCard,
              const SizedBox(height: 12),
              button,
              alerts,
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: history),
                  ],
                )
              else ...[
                left,
                const SizedBox(height: 16),
                history,
              ],
            ],
          );
        },
      ),
    );
  }
}
