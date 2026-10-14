import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/form_dialog.dart';
import 'attendance_models.dart';
import 'attendance_providers.dart';

class EmployeesTab extends ConsumerWidget {
  const EmployeesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(employeesProvider).value ?? <Employee>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Karyawan'),
      ),
      body: list.isEmpty
          ? const Center(child: Text('Belum ada karyawan'))
          : ListView(
              children: [
                for (final e in list)
                  ListTile(
                    title: Text('${e.name}${e.active ? '' : ' (nonaktif)'}'),
                    subtitle: Text(
                      [
                        if (e.position.isNotEmpty) e.position,
                        e.hasPin ? 'PIN diatur' : 'PIN belum diatur',
                      ].join(' • '),
                    ),
                    onTap: () => _edit(context, ref, e),
                    onLongPress: () => _menu(context, ref, e),
                  ),
              ],
            ),
    );
  }

  void _toast(BuildContext c, String m) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Employee? e) async {
    final r = await formDialog(
      context,
      e == null ? 'Karyawan baru' : 'Edit karyawan',
      [
        'Nama',
        'Jabatan',
        e == null
            ? 'PIN (4–6 angka)'
            : 'PIN baru (kosongkan jika tidak diubah)',
      ],
      initial: [e?.name ?? '', e?.position ?? '', ''],
      numeric: {2},
    );
    if (r == null) return;
    if (r[0].isEmpty) {
      _toast(context, 'Nama wajib diisi');
      return;
    }
    final pin = r[2];
    if (e == null && !isValidPin(pin)) {
      _toast(context, 'PIN wajib 4–6 angka');
      return;
    }
    if (pin.isNotEmpty && !isValidPin(pin)) {
      _toast(context, 'PIN harus 4–6 angka');
      return;
    }
    final salt = pin.isEmpty ? (e?.pinSalt ?? '') : newSalt();
    final hash = pin.isEmpty ? (e?.pinHash ?? '') : hashPin(pin, salt);
    await ref
        .read(employeeRepositoryProvider)
        .save(
          Employee(
            id: e?.id ?? const Uuid().v4(),
            name: r[0],
            position: r[1],
            pinHash: hash,
            pinSalt: salt,
            active: e?.active ?? true,
          ),
        );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, Employee e) async {
    final hasRecords = (ref.read(attendanceProvider).value ?? <Attendance>[])
        .any((a) => a.employeeId == e.id);
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(e.name)),
            ListTile(
              leading: Icon(
                e.active ? Icons.block : Icons.check_circle_outline,
              ),
              title: Text(e.active ? 'Nonaktifkan' : 'Aktifkan'),
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
            if (!hasRecords)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Hapus'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (a == 'toggle') {
      await ref
          .read(employeeRepositoryProvider)
          .save(e.copyWith(active: !e.active));
    } else if (a == 'delete') {
      await ref.read(employeeRepositoryProvider).remove(e.id);
    }
  }
}
