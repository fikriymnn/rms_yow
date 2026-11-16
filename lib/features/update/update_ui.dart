import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ota_update/ota_update.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import 'update_models.dart';
import 'update_service.dart';

String _otaError(String status) => switch (status) {
  'PERMISSION_NOT_GRANTED_ERROR' =>
    'Izin memasang aplikasi belum diberikan. Aktifkan "Izinkan dari sumber ini" '
        'di layar yang muncul, lalu tekan Perbarui lagi.',
  'CHECKSUM_ERROR' => 'Berkas unduhan rusak. Coba lagi.',
  'DOWNLOAD_ERROR' => 'Unduhan gagal. Periksa koneksi internet lalu coba lagi.',
  'ALREADY_RUNNING_ERROR' => 'Pembaruan sedang berjalan.',
  'CANCELED' => 'Pembaruan dibatalkan.',
  _ => 'Pembaruan gagal ($status). Coba lagi.',
};

/// Dialog pembaruan: catatan versi, unduh dengan progres, lalu buka pemasang Android.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info, this.mandatory = false});
  final UpdateInfo info;
  final bool mandatory;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  bool _busy = false;
  int _progress = 0;
  String _phase = '';
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
      _phase = 'Mengunduh...';
    });
    try {
      _sub = OtaUpdate()
          .execute(
            widget.info.url,
            destinationFilename: 'rms-${widget.info.build}.apk',
            sha256checksum: widget.info.sha256,
          )
          .listen(
            (e) {
              if (!mounted) return;
              final s = e.status.name.toUpperCase();
              setState(() {
                if (s == 'DOWNLOADING') {
                  _progress = int.tryParse(e.value ?? '') ?? _progress;
                } else if (s == 'INSTALLING') {
                  _phase = 'Membuka pemasang Android...';
                } else if (s == 'INSTALLATION_DONE') {
                  _phase = 'Selesai';
                } else if (s.endsWith('ERROR') || s == 'CANCELED') {
                  _busy = false;
                  _error = _otaError(s);
                }
              });
            },
            onError: (Object e) {
              if (!mounted) return;
              setState(() {
                _busy = false;
                _error = errorText(e);
              });
            },
          );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    return PopScope(
      canPop: !widget.mandatory && !_busy,
      child: AlertDialog(
        title: Text(
          widget.mandatory ? 'Pembaruan wajib' : 'Pembaruan tersedia',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versi ${i.version} • ${i.sizeText}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              if (i.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(i.notes),
              ],
              if (widget.mandatory) ...[
                const SizedBox(height: 10),
                Text(
                  'Versi aplikasi ini sudah tidak didukung server. Perbarui untuk '
                  'melanjutkan.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                ),
                const SizedBox(height: 6),
                Text(
                  _progress > 0 ? '$_phase $_progress%' : _phase,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.mandatory && !_busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti'),
            ),
          FilledButton(
            onPressed: _busy ? null : _start,
            child: Text(_error == null ? 'Perbarui' : 'Coba lagi'),
          ),
        ],
      ),
    );
  }
}

Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  bool mandatory = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: !mandatory,
  builder: (_) => UpdateDialog(info: info, mandatory: mandatory),
);

/// Tombol "Cek pembaruan" (halaman Akun).
Future<void> checkForUpdateManually(BuildContext context, WidgetRef ref) async {
  void say(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  try {
    final info = await ref.read(updateCheckerProvider)();
    final v = await ref.read(appVersionProvider.future);
    ref.invalidate(latestUpdateProvider);
    if (!context.mounted) return;
    if (info != null && info.isNewerThan(v.build)) {
      await showUpdateDialog(
        context,
        info,
        mandatory: info.isMandatoryFor(v.build),
      );
    } else {
      say('Aplikasi sudah versi terbaru (v${v.name}).');
    }
  } catch (_) {
    say('Tidak bisa terhubung ke server untuk memeriksa pembaruan.');
  }
}

/// Layar penghalang: versi aplikasi di bawah batas minimum server.
class UpdateRequiredPage extends ConsumerWidget {
  const UpdateRequiredPage({super.key, required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.system_update_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Pembaruan diperlukan',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi ${info.version} (${info.sizeText}) harus dipasang sebelum '
                'aplikasi bisa dipakai.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () =>
                    showUpdateDialog(context, info, mandatory: true),
                icon: const Icon(Icons.download),
                label: const Text('Perbarui sekarang'),
              ),
              TextButton(
                onPressed: () => ref.invalidate(latestUpdateProvider),
                child: const Text('Periksa lagi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
