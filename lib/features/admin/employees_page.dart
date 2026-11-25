import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../../shell/app_bar.dart';
import '../auth/auth_providers.dart';
import '../client/client_providers.dart';
import 'account_dialog.dart';
import 'employee_models.dart';

class _Data {
  _Data(this.items, this.outlets);
  final List<EmployeeInfo> items;
  final List<OutletInfo> outlets;
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// Data karyawan: semua orang yang bekerja, dengan atau tanpa akun login.
/// Karyawan tanpa akun tetap bisa absen lewat Absen bersama (pakai PIN) dan ikut penggajian.
class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});
  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  String? _filterOutlet; // hanya owner
  String _query = '';
  late Future<_Data> _future = _load();

  Future<_Data> _load() async {
    final api = ref.read(apiClientProvider);
    final session = ref.read(sessionProvider).value!;
    final items = [
      for (final m in await api.get(
            '/employees',
            query: {if (_filterOutlet != null) 'outlet_id': _filterOutlet},
          ) as List<dynamic>)
        EmployeeInfo.fromJson(m as Map<String, dynamic>),
    ];
    final outlets = session.user.isOwner
        ? [
            for (final m in await api.get('/outlets') as List<dynamic>)
              OutletInfo.fromJson(m as Map<String, dynamic>),
          ]
        : [if (session.outlet != null) session.outlet!];
    return _Data(items, outlets);
  }

  void _reload() => setState(() => _future = _load());

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() job, {String? ok}) async {
    try {
      await job();
      if (ok != null) _toast(ok);
      _reload();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  /// Form tambah/edit. Kembalikan body request, atau null bila dibatalkan.
  Future<Map<String, dynamic>?> _form(EmployeeInfo? e, List<OutletInfo> outlets) {
    final isOwner = ref.read(sessionProvider).value!.user.isOwner;
    final name = TextEditingController(text: e?.name);
    final position = TextEditingController(text: e?.position);
    final pin = TextEditingController();
    String? outletId = e?.outletId ?? (outlets.length == 1 ? outlets.first.id : null);
    var active = e?.active ?? true;
    var clearPin = false;
    final attendanceOn = ref.read(moduleEnabledProvider('attendance'));

    return showAppDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final p = pin.text.trim();
          final pinOk = p.isEmpty || RegExp(r'^\d{4,6}$').hasMatch(p);
          final valid = name.text.trim().isNotEmpty && outletId != null && pinOk;
          return AlertDialog(
            title: Text(e == null ? 'Karyawan baru' : 'Edit karyawan'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: name,
                      autofocus: e == null,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nama'),
                      onChanged: (_) => setS(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: position,
                      decoration: const InputDecoration(labelText: 'Jabatan (mis. Kasir, Cook)'),
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: outletId,
                        isExpanded: true,
                        hint: const Text('Pilih outlet'),
                        decoration: const InputDecoration(labelText: 'Outlet'),
                        items: [
                          for (final o in outlets) DropdownMenuItem(value: o.id, child: Text(o.name)),
                        ],
                        onChanged: (v) => setS(() => outletId = v),
                      ),
                    ],
                    if (attendanceOn) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pin,
                      enabled: !clearPin,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'PIN absensi (4–6 angka)',
                        helperText: e == null
                            ? 'Dipakai saat absen di Absen bersama. Boleh diisi nanti.'
                            : (e.pinSet
                                ? 'Sudah diatur. Kosongkan bila tidak ingin mengganti.'
                                : 'Belum diatur. Isi agar bisa absen di Absen bersama.'),
                        errorText: pinOk ? null : 'PIN harus 4–6 angka',
                        counterText: '',
                      ),
                      onChanged: (_) => setS(() {}),
                    ),
                    ],
                    if (attendanceOn && e != null && e.pinSet)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: clearPin,
                        title: const Text('Hapus PIN'),
                        onChanged: (v) => setS(() {
                          clearPin = v ?? false;
                          if (clearPin) pin.clear();
                        }),
                      ),
                    if (e != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        title: const Text('Aktif'),
                        subtitle: Text(
                          active
                              ? 'Ikut absensi & penggajian'
                              : e.hasAccount
                                  ? 'Akun loginnya ikut dinonaktifkan'
                                  : 'Tidak ikut absensi & penggajian',
                        ),
                        onChanged: (v) => setS(() => active = v),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(ctx, {
                          'name': name.text.trim(),
                          'position': position.text.trim(),
                          if (isOwner && (e == null || outletId != e.outletId)) 'outlet_id': outletId,
                          if (p.isNotEmpty) 'pin': p,
                          if (e != null && clearPin) 'clear_pin': true,
                          if (e != null && active != e.active) 'active': active,
                        })
                    : null,
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(List<OutletInfo> outlets) async {
    final body = await _form(null, outlets);
    if (body == null) return;
    await _run(() async {
      await ref.read(apiClientProvider).post('/employees', data: body);
    }, ok: 'Karyawan ditambahkan');
  }

  Future<void> _edit(EmployeeInfo e, List<OutletInfo> outlets) async {
    final body = await _form(e, outlets);
    if (body == null) return;
    await _run(() async {
      await ref.read(apiClientProvider).request('PATCH', '/employees/${e.id}', data: body);
    }, ok: 'Perubahan disimpan');
  }

  Future<void> _delete(EmployeeInfo e) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${e.name}?'),
        content: const Text(
          'Data karyawan dihapus permanen. Karyawan yang sudah punya riwayat absensi atau '
          'slip gaji tidak bisa dihapus — nonaktifkan saja.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(apiClientProvider).request('DELETE', '/employees/${e.id}');
    }, ok: 'Karyawan dihapus');
  }

  Future<void> _actions(EmployeeInfo e, List<OutletInfo> outlets) async {
    final me = ref.read(appUserProvider).value;
    final canAccount = me?.can('users.create') ?? false;
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                e.name,
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                e.hasAccount ? '@${e.username} • ${e.roleName}' : 'Belum punya akun login',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit data & PIN'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            if (!e.hasAccount && e.active && canAccount)
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Buat akun login'),
                subtitle: const Text('Agar karyawan bisa masuk aplikasi'),
                onTap: () => Navigator.pop(ctx, 'account'),
              ),
            if (!e.hasAccount)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Hapus'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'edit':
        await _edit(e, outlets);
      case 'account':
        if (await showCreateAccountDialog(context, ref, preset: e)) {
          _toast('Akun login dibuat untuk ${e.name}');
          _reload();
        }
      case 'delete':
        await _delete(e);
    }
  }

  Widget _card(EmployeeInfo e, String outletName, VoidCallback onTap) {
    final attendanceOn = ref.read(moduleEnabledProvider('attendance'));
    return Material(
      color: e.active ? AppColors.surface : AppColors.divider,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: e.active
                    ? (e.hasAccount ? AppColors.primary : AppColors.sage)
                    : const Color(0xFFD6CEC2),
                child: Text(
                  _initials(e.name),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: e.active ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    Text(
                      [if (e.position.isNotEmpty) e.position, outletName].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        e.hasAccount
                            ? StatusPill('Akun: ${e.roleName}', tone: Tone.info)
                            : const StatusPill('Tanpa akun'),
                        if (attendanceOn)
                          e.pinSet
                              ? const StatusPill('PIN siap', tone: Tone.success)
                              : const StatusPill('PIN belum', tone: Tone.warning),
                        if (!e.active) const StatusPill('Nonaktif', tone: Tone.danger),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_vert, size: 20, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).value?.user;
    if (me == null) return const SizedBox.shrink();
    final canCreate = ref.watch(appUserProvider).value?.can('users.create') ?? false;
    final attendanceOn = ref.watch(moduleEnabledProvider('attendance'));

    return Scaffold(
      appBar: RmsAppBar(title: const Text('Data karyawan')),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: AppLoader());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorText(snap.error!)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Coba lagi')),
                ],
              ),
            );
          }
          final d = snap.data!;
          String outletName(String? id) =>
              d.outlets.where((o) => o.id == id).firstOrNull?.name ?? '-';
          final shown = d.items
              .where((e) =>
                  _query.isEmpty ||
                  e.name.toLowerCase().contains(_query) ||
                  e.position.toLowerCase().contains(_query))
              .toList();
          final noPin = attendanceOn ? d.items.where((e) => e.active && !e.pinSet).length : 0;
          final noAccount = d.items.where((e) => !e.hasAccount).length;

          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: canCreate
                ? FloatingActionButton.extended(
                    onPressed: d.outlets.isEmpty ? null : () => _create(d.outlets),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Karyawan'),
                  )
                : null,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  attendanceOn
                      ? 'Karyawan tidak wajib punya akun. Tanpa akun pun tetap bisa absen di '
                          'Absen bersama memakai PIN, dan ikut penggajian.'
                      : 'Karyawan tidak wajib punya akun. Akun login dibuat dari data karyawan.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill('${d.items.length} karyawan', tone: Tone.info),
                    if (noAccount > 0) StatusPill('$noAccount tanpa akun'),
                    if (noPin > 0) StatusPill('$noPin belum ada PIN', tone: Tone.warning),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau jabatan',
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (me.isOwner) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _filterOutlet,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Filter outlet'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Semua outlet')),
                      for (final o in d.outlets)
                        DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
                    ],
                    onChanged: (v) {
                      _filterOutlet = v;
                      _reload();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Belum ada karyawan',
                    message: 'Tambahkan karyawan dengan tombol di kanan bawah.',
                  )
                else
                  AdaptiveGrid(
                    minTileWidth: 380,
                    maxColumns: 3,
                    children: [
                      for (final e in shown)
                        _card(e, outletName(e.outletId), () => _actions(e, d.outlets)),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
