import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../roles/role_models.dart';
import 'employee_models.dart';

Future<List<RoleOption>> _assignableRoles(WidgetRef ref) async {
  final raw = await ref.read(apiClientProvider).get('/users/role-options') as List<dynamic>;
  return [
    for (final m in raw)
      if ((m as Map)['assignable'] == true) RoleOption.fromJson(Map<String, dynamic>.from(m)),
  ];
}

/// Buat akun login untuk DATA KARYAWAN yang belum punya akun.
/// [preset] = karyawan yang sudah dipilih (dari halaman Data karyawan); null = pilih dari daftar.
/// Kembalikan true bila akun dibuat.
Future<bool> showCreateAccountDialog(
  BuildContext context,
  WidgetRef ref, {
  EmployeeInfo? preset,
}) async {
  final api = ref.read(apiClientProvider);
  final List<RoleOption> roles;
  final List<EmployeeInfo> candidates;
  try {
    roles = await _assignableRoles(ref);
    candidates = preset != null
        ? [preset]
        : [
            for (final m in await api.get('/employees', query: {'active': true}) as List<dynamic>)
              EmployeeInfo.fromJson(m as Map<String, dynamic>),
          ].where((e) => !e.hasAccount).toList();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
    return false;
  }
  if (!context.mounted) return false;
  if (roles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anda tidak punya role yang boleh diberikan.')),
    );
    return false;
  }
  if (candidates.isEmpty) {
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belum ada data karyawan'),
        content: const Text(
          'Akun login dibuat dari data karyawan. Tambahkan dulu karyawannya di '
          'Data Master → Karyawan, lalu buat akunnya.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
        ],
      ),
    );
    return false;
  }

  final username = TextEditingController();
  final password = TextEditingController();
  String? employeeId = preset?.id ?? (candidates.length == 1 ? candidates.first.id : null);
  var role = roles.first.key;
  String? error;
  var saving = false;

  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final valid =
            employeeId != null && username.text.trim().length >= 3 && password.text.length >= 8;
        Future<void> save() async {
          setS(() {
            saving = true;
            error = null;
          });
          try {
            await api.post(
              '/users',
              data: {
                'employee_id': employeeId,
                'username': username.text.trim(),
                'password': password.text,
                'role': role,
              },
            );
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            setS(() {
              saving = false;
              error = errorText(e);
            });
          }
        }

        return AlertDialog(
          title: const Text('Buat akun login'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Akun dipakai karyawan untuk login aplikasi. Nama, jabatan, dan outlet '
                    'mengikuti data karyawan.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  if (preset != null)
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Karyawan'),
                      child: Text(
                        preset.name,
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: employeeId,
                      isExpanded: true,
                      hint: const Text('Pilih data karyawan'),
                      decoration: const InputDecoration(labelText: 'Karyawan'),
                      items: [
                        for (final e in candidates)
                          DropdownMenuItem(
                            value: e.id,
                            child: Text(
                              e.position.isEmpty ? e.name : '${e.name} · ${e.position}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setS(() => employeeId = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: username,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Username (huruf, angka, . _ -)'),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password awal (min. 8)',
                      helperText: 'Karyawan wajib menggantinya saat login pertama',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true, // pilihan bernama panjang tidak overflow
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role (hak akses)'),
                    items: [
                      for (final r in roles) DropdownMenuItem(value: r.key, child: Text(r.name)),
                    ],
                    onChanged: (v) => setS(() => role = v ?? role),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: valid && !saving ? save : null,
              child: Text(saving ? 'Menyimpan…' : 'Buat akun'),
            ),
          ],
        );
      },
    ),
  );
  username.dispose();
  password.dispose();
  return ok == true;
}
