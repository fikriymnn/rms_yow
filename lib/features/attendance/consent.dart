import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'attendance_queue.dart';

/// Harus sama dengan ATTENDANCE_CONSENT_VERSION di server.
const kConsentVersion = 1;

/// Dialog persetujuan. [forName] diisi di tablet kiosk (karyawan yang sedang absen).
Future<bool> askConsentAgreement(
  BuildContext context, {
  String? forName,
}) async {
  var agreed = false;
  final who = forName == null ? '' : ' $forName';
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Persetujuan data absensi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Untuk mencatat kehadiran$who, aplikasi akan:\n\n'
                '• Membaca lokasi GPS saat tombol absen ditekan.\n'
                '• Mengambil foto wajah (selfie) dan memeriksa bahwa wajah ada di depan kamera.\n\n'
                'Data ini hanya dipakai untuk memverifikasi absensi. Yang dapat melihatnya: '
                'karyawan yang bersangkutan, manager outlet, dan owner. Foto dihapus otomatis setelah '
                'masa simpan (saat ini 90 hari), sedangkan catatan jam masuk dan pulang tetap ada.\n\n'
                'Persetujuan dicatat di server (waktu dan versi teks ini).',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: agreed,
                onChanged: (v) => setS(() => agreed = v ?? false),
                title: const Text('Saya mengerti dan setuju'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: agreed ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Lanjut'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// Persetujuan data lokasi dan foto wajah. Tersimpan di server (waktu dan versi).
Future<bool> ensureConsent(BuildContext context, WidgetRef ref) async {
  await ref
      .read(attendanceMeProvider.notifier)
      .refresh(); // status terbaru bila online
  if (ref.read(attendanceMeProvider).value?.consentVersion == kConsentVersion) {
    return true;
  }
  if (!context.mounted) return false;
  if (!await askConsentAgreement(context)) return false;
  try {
    await ref
        .read(apiClientProvider)
        .post('/attendance/consent', data: {'version': kConsentVersion});
    await ref.read(attendanceMeProvider.notifier).refresh();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is DioException
                ? 'Persetujuan pertama harus dilakukan saat online.'
                : errorText(e),
          ),
        ),
      );
    }
    return false;
  }
}

/// Cabut persetujuan (hak subjek data). Mengembalikan jumlah foto yang dihapus di server,
/// atau null bila dibatalkan atau gagal.
Future<int?> revokeConsent(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cabut persetujuan data absensi?'),
      content: const Text(
        'Yang terjadi:\n\n'
        '• Foto wajah Anda dan koordinat lokasi pada catatan absensi dihapus permanen.\n'
        '• Foto yang masih mengantre di HP ini juga dihapus.\n'
        '• Catatan jam masuk dan pulang tetap ada.\n'
        '• Anda tidak bisa absen sampai menyetujui lagi.\n\n'
        'Tindakan ini tidak bisa dibatalkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cabut dan hapus'),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  try {
    final m =
        await ref.read(apiClientProvider).post('/attendance/consent/revoke')
            as Map<String, dynamic>;
    await ref.read(attendanceQueueProvider).clearAll();
    await ref.read(attendanceMeProvider.notifier).refresh();
    return (m['photos_deleted'] as num).toInt();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
    return null;
  }
}
