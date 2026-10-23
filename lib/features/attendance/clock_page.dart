import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Absensi')),
        body: const Center(
          child: Text('Absensi hanya tersedia di aplikasi Android.'),
        ),
      );
    }
    final session = ref.watch(sessionProvider).value;
    final outlet = session?.outlet;
    final me = ref.watch(attendanceMeProvider).value;
    final queue = ref.watch(queueItemsProvider).value ?? <QueueItem>[];
    final cs = Theme.of(context).colorScheme;
    final th = Theme.of(context).textTheme;
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
    Color locColor = cs.onSurface;
    if (outlet == null) {
      locText = 'Akun ini tidak terikat outlet.';
    } else if (!hasOutletLoc) {
      locText =
          'Lokasi outlet belum diatur. Minta owner mengaturnya di Kelola outlet.';
      locColor = cs.error;
    } else if (_locError != null) {
      locText = _locError!.message;
      locColor = cs.error;
    } else if (fix == null) {
      locText = 'Mencari sinyal GPS...';
    } else if (mocked) {
      locText =
          'Lokasi palsu (mock location) terdeteksi. Matikan aplikasi lokasi palsu.';
      locColor = cs.error;
    } else if (!accuracyOk) {
      locText =
          'Akurasi GPS kurang (±${fix.accuracy.round()} m). Pindah ke tempat terbuka.';
      locColor = cs.error;
    } else if (area.inArea) {
      locText = 'Dalam area outlet (±${area.distance!.round()} m dari titik)';
      locColor = Colors.green.shade700;
    } else {
      locText =
          'Di luar area outlet (±${area.distance!.round()} m, batas ${outlet!.radiusM} m)';
      locColor = cs.error;
    }

    final staleRecords = (me?.recent ?? const <AttendanceRecord>[]).where(
      (r) => r.stale,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: Text(_hm.format(now), style: th.displaySmall)),
          Center(child: Text('${_day.format(now)} • ${outlet?.name ?? '-'}')),
          const SizedBox(height: 16),
          Card(
            color: isOpen ? cs.primaryContainer : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (_) {
                  final open = me?.open;
                  if (pending.isNotEmpty &&
                      pending.last.kind == 'in' &&
                      open == null) {
                    return const Text(
                      'Sedang bekerja (absen masuk menunggu dikirim)',
                    );
                  }
                  if (open != null && isOpen) {
                    final mins =
                        ((now.millisecondsSinceEpoch - open.clockInAt) / 60000)
                            .round();
                    return Text(
                      'Sedang bekerja sejak ${_hm.format(DateTime.fromMillisecondsSinceEpoch(open.clockInAt))} • ${durationText(mins)}',
                      style: th.titleMedium,
                    );
                  }
                  return Text(
                    isOpen ? 'Sedang bekerja' : 'Belum absen masuk',
                    style: th.titleMedium,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.place_outlined, color: locColor),
            title: Text(locText, style: TextStyle(color: locColor)),
            subtitle: fix == null
                ? null
                : Text('Akurasi GPS ±${fix.accuracy.round()} m'),
            trailing: (_locError?.openSettings ?? false)
                ? TextButton(
                    onPressed: Geolocator.openAppSettings,
                    child: const Text('Pengaturan'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: canClock ? () => _clock(kind) : null,
              icon: Icon(isOpen ? Icons.logout : Icons.login),
              label: Text(isOpen ? 'Absen pulang' : 'Absen masuk'),
            ),
          ),
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${pending.length} absen menunggu dikirim ke server',
                style: TextStyle(color: cs.tertiary),
              ),
            ),
          for (final q in rejected)
            Card(
              color: cs.errorContainer,
              child: ListTile(
                title: Text(
                  'Absen ${q.kind == 'in' ? 'masuk' : 'pulang'} '
                  '${_hm.format(DateTime.fromMillisecondsSinceEpoch(q.clientTime))} ditolak',
                ),
                subtitle: Text(q.error),
                trailing: IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      ref.read(attendanceQueueProvider).dismiss(q.eventId),
                ),
              ),
            ),
          for (final r in staleRecords)
            Card(
              color: cs.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(
                  'Lupa absen pulang (${_day.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt))})',
                ),
                subtitle: const Text(
                  'Hubungi manager untuk mengoreksi jam pulang.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('14 hari terakhir', style: th.titleMedium),
          const Divider(),
          if (me == null || me.recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Belum ada catatan'),
            ),
          for (final r in me?.recent ?? const <AttendanceRecord>[])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_day.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt))}   '
                '${_hm.format(DateTime.fromMillisecondsSinceEpoch(r.clockInAt))} - '
                '${r.clockOutAt == null ? '...' : _hm.format(DateTime.fromMillisecondsSinceEpoch(r.clockOutAt!))}',
              ),
              subtitle: Text(
                [
                  if (r.minutes != null) durationText(r.minutes!),
                  if (r.edited) 'dikoreksi',
                  if (r.inFlags.contains('late_sync')) 'dikirim terlambat',
                  if (r.reviewStatus == 'suspicious') 'ditandai manager',
                ].join(' • '),
              ),
            ),
        ],
      ),
    );
  }
}
