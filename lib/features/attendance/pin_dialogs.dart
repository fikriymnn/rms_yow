import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';

final _pinRe = RegExp(r'^\d{4,6}$');

/// Manager/owner mengatur PIN absensi karyawan.
/// Mengembalikan pesan untuk ditampilkan, atau null bila dibatalkan.
Future<String?> promptSetPin(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final r = await formDialog(
    context,
    'PIN absensi $name',
    ['PIN baru (4–6 angka)'],
    obscure: {0},
    okLabel: 'Simpan',
    hint: 'PIN dipakai karyawan saat absen di tablet bersama.',
  );
  if (r == null) return null;
  if (!_pinRe.hasMatch(r[0])) return 'PIN harus 4–6 angka';
  try {
    await ref
        .read(apiClientProvider)
        .request(
          'PUT',
          '/attendance/pin/$userId',
          dataBuilder: () => {'pin': r[0]},
        );
    return 'PIN $name disimpan';
  } catch (e) {
    return errorText(e);
  }
}

/// Karyawan mengatur PIN sendiri (butuh password akun).
Future<String?> promptSetMyPin(BuildContext context, WidgetRef ref) async {
  final r = await formDialog(
    context,
    'PIN absensi saya',
    ['Password akun', 'PIN baru (4–6 angka)'],
    obscure: {0, 1},
    okLabel: 'Simpan',
    hint: 'PIN dipakai saat absen di tablet bersama.',
  );
  if (r == null) return null;
  if (r[0].isEmpty) return 'Password wajib diisi';
  if (!_pinRe.hasMatch(r[1])) return 'PIN harus 4–6 angka';
  try {
    await ref
        .read(apiClientProvider)
        .request(
          'PUT',
          '/attendance/pin/me',
          dataBuilder: () => {'password': r[0], 'pin': r[1]},
        );
    return 'PIN absensi disimpan';
  } catch (e) {
    return errorText(e);
  }
}
