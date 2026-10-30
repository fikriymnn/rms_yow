import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import '../roles/role_models.dart';
import 'managed_user.dart';

class _Data {
  _Data(this.users, this.outlets);
  final List<ManagedUser> users;
  final List<OutletInfo> outlets;
}

String _initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

class UsersAdminPage extends ConsumerStatefulWidget {
  const UsersAdminPage({super.key});
  @override
  ConsumerState<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends ConsumerState<UsersAdminPage> {
  String? _filterOutlet; // hanya owner
  String _query = '';
  late Future<_Data> _future = _load();
  List<RoleOption> _roleOptions = const [];

  String _roleName(String key) => roleNameOf(key, _roleOptions);

  Future<_Data> _load() async {
    final api = ref.read(apiClientProvider);
    final session = ref.read(sessionProvider).value!;
    final users = [
      for (final m
          in await api.get(
                '/users',
                query: {
                  if (_filterOutlet != null) 'outlet_id': _filterOutlet,
                  'limit': 500,
                },
              )
              as List<dynamic>)
        ManagedUser.fromJson(m as Map<String, dynamic>),
    ];
    final outlets = session.user.isOwner
        ? [
            for (final m in await api.get('/outlets') as List<dynamic>)
              OutletInfo.fromJson(m as Map<String, dynamic>),
          ]
        : [if (session.outlet != null) session.outlet!];
    _roleOptions = [
      for (final m in await api.get('/users/role-options') as List<dynamic>)
        RoleOption.fromJson(m as Map<String, dynamic>),
    ];
    return _Data(users, outlets);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

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

  Future<Map<String, dynamic>?> _userForm(
    ManagedUser? u,
    List<OutletInfo> outlets,
  ) {
    final me = ref.read(sessionProvider).value!.user;
    final roles = _roleOptions.where((o) => o.assignable).toList();
    if (roles.isEmpty) {
      _toast('Anda tidak punya role yang boleh diberikan.');
      return Future.value(null);
    }
    final isOwner = me.isOwner;
    final username = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController(text: u?.name);
    final position = TextEditingController(text: u?.position);
    var role = (u != null && roles.any((o) => o.key == u.roleKey))
        ? u.roleKey
        : roles.first.key;
    String? outletId =
        u?.outletId ?? (outlets.length == 1 ? outlets.first.id : null);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final valid =
              name.text.trim().isNotEmpty &&
              (u != null ||
                  (username.text.trim().length >= 3 &&
                      password.text.length >= 8)) &&
              (!isOwner || outletId != null);
          return AlertDialog(
            title: Text(u == null ? 'Pengguna baru' : 'Edit pengguna'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (u == null) ...[
                      TextField(
                        controller: username,
                        autofocus: true,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Username (huruf, angka, . _ -)',
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password awal (min. 8)',
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nama'),
                      onChanged: (_) => setS(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: position,
                      decoration: const InputDecoration(labelText: 'Jabatan'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final r in roles)
                          DropdownMenuItem(value: r.key, child: Text(r.name)),
                      ],
                      onChanged: (v) => setS(() => role = v ?? role),
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: outletId,
                        isExpanded: true,
                        hint: const Text('Pilih outlet'),
                        decoration: const InputDecoration(labelText: 'Outlet'),
                        items: [
                          for (final o in outlets)
                            DropdownMenuItem(value: o.id, child: Text(o.name)),
                        ],
                        onChanged: (v) => setS(() => outletId = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(ctx, {
                        'username': username.text.trim(),
                        'password': password.text,
                        'name': name.text.trim(),
                        'position': position.text.trim(),
                        'role': role,
                        'outlet_id': outletId,
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
    final r = await _userForm(null, outlets);
    if (r == null) return;
    final isOwner = ref.read(sessionProvider).value!.user.isOwner;
    await _run(() async {
      await ref
          .read(apiClientProvider)
          .post(
            '/users',
            data: {
              'username': r['username'],
              'password': r['password'],
              'name': r['name'],
              'position': r['position'],
              'role': r['role'],
              if (isOwner) 'outlet_id': r['outlet_id'],
            },
          );
    }, ok: 'Pengguna dibuat');
  }

  Future<void> _edit(ManagedUser u, List<OutletInfo> outlets) async {
    final r = await _userForm(u, outlets);
    if (r == null) return;
    final isOwner = ref.read(sessionProvider).value!.user.isOwner;
    await _run(() async {
      await ref
          .read(apiClientProvider)
          .request(
            'PATCH',
            '/users/${u.id}',
            data: {
              'name': r['name'],
              'position': r['position'],
              'role': r['role'],
              if (isOwner && r['outlet_id'] != u.outletId)
                'outlet_id': r['outlet_id'],
            },
          );
    }, ok: 'Perubahan disimpan');
  }

  Future<void> _resetPassword(ManagedUser u) async {
    final r = await formDialog(
      context,
      'Reset password ${u.name}',
      ['Password baru (min. 8 karakter)'],
      obscure: {0},
      okLabel: 'Reset',
    );
    if (r == null) return;
    if (r[0].length < 8) {
      _toast('Password minimal 8 karakter');
      return;
    }
    await _run(() async {
      await ref
          .read(apiClientProvider)
          .post('/users/${u.id}/reset-password', data: {'new_password': r[0]});
    }, ok: 'Password direset. ${u.name} harus login ulang.');
  }

  Future<void> _actions(ManagedUser u, List<OutletInfo> outlets) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                u.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text('${u.username} • ${_roleName(u.roleKey)}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Reset password'),
              onTap: () => Navigator.pop(ctx, 'reset'),
            ),
            ListTile(
              leading: Icon(
                u.active ? Icons.block : Icons.check_circle_outline,
                color: u.active ? AppColors.danger : AppColors.success,
              ),
              title: Text(u.active ? 'Nonaktifkan' : 'Aktifkan'),
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case 'edit':
        await _edit(u, outlets);
      case 'reset':
        await _resetPassword(u);
      case 'toggle':
        await _run(() async {
          await ref
              .read(apiClientProvider)
              .post('/users/${u.id}/${u.active ? 'deactivate' : 'activate'}');
        }, ok: u.active ? 'Akun dinonaktifkan' : 'Akun diaktifkan');
    }
  }

  Widget _card(
    ManagedUser u,
    String outletName,
    bool canEdit,
    VoidCallback onTap,
  ) {
    final senior =
        u.roleKey == 'owner' ||
        u.roleKey == 'manager' ||
        u.roleKey == 'head_chef';
    return Material(
      color: u.active ? AppColors.surface : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit ? onTap : null,
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
                backgroundColor: u.active
                    ? AppColors.primary
                    : const Color(0xFFD1D5DB),
                child: Text(
                  _initials(u.name),
                  style: GoogleFonts.inter(
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
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: u.active ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    Text(
                      '@${u.username} • $outletName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(
                          _roleName(u.roleKey),
                          tone: senior ? Tone.info : Tone.neutral,
                        ),
                        if (!u.active)
                          const StatusPill('Nonaktif', tone: Tone.danger),
                      ],
                    ),
                  ],
                ),
              ),
              if (canEdit)
                const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola pengguna')),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorText(snap.error!)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }
          final d = snap.data!;
          String outletName(String? id) =>
              d.outlets.where((o) => o.id == id).firstOrNull?.name ??
              (id == null ? 'Semua outlet' : '-');
          final shown = d.users
              .where(
                (u) =>
                    _query.isEmpty ||
                    u.name.toLowerCase().contains(_query) ||
                    u.username.toLowerCase().contains(_query),
              )
              .toList();
          final inactive = d.users.where((u) => !u.active).length;

          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: d.outlets.isEmpty ? null : () => _create(d.outlets),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Pengguna'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Row(
                  children: [
                    StatusPill('${d.users.length} pengguna', tone: Tone.info),
                    const SizedBox(width: 8),
                    if (inactive > 0) StatusPill('$inactive nonaktif'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau username',
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (me.isOwner) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _filterOutlet,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filter outlet',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Semua outlet'),
                      ),
                      for (final o in d.outlets)
                        DropdownMenuItem<String?>(
                          value: o.id,
                          child: Text(o.name),
                        ),
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
                    icon: Icons.people_outline,
                    title: 'Tidak ada pengguna',
                  )
                else
                  AdaptiveGrid(
                    minTileWidth: 380,
                    maxColumns: 3,
                    children: [
                      for (final u in shown)
                        _card(
                          u,
                          outletName(u.outletId),
                          canManageUser(me, u, _roleOptions),
                          () => _actions(u, d.outlets),
                        ),
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
