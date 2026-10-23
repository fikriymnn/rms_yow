import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'attendance_queue.dart';

/// Harus sama dengan ATTENDANCE_CONSENT_VERSION di server.
const kConsentVersion = 1;

/// Persetujuan data lokasi dan foto wajah. Tersimpan di server (waktu dan versi).
Future<bool> ensureConsent(BuildContext context, WidgetRef ref) async {
  await ref
      .read(attendanceMeProvider.notifier)
      .refresh(); // status terbaru bila online
  if (ref.read(attendanceMeProvider).value?.consentVersion == kConsentVersion)
    return true;
  if (!context.mounted) return false;

  var agreed = false;
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
              const Text(
                'Untuk mencatat kehadiran, aplikasi akan:\n\n'
                '• Membaca lokasi GPS Anda saat Anda menekan tombol absen.\n'
                '• Mengambil foto wajah (selfie) dan memeriksa bahwa wajah Anda ada di depan kamera.\n\n'
                'Data ini hanya dipakai untuk memverifikasi absensi. Yang dapat melihatnya: '
                'Anda sendiri, manager outlet Anda, dan owner. Foto dihapus otomatis setelah '
                'masa simpan (saat ini 90 hari), sedangkan catatan jam masuk dan pulang tetap ada.\n\n'
                'Persetujuan Anda dicatat di server (waktu dan versi teks ini).',
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
  if (ok != true) return false;
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
