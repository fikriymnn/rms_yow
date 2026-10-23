import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../auth/auth_providers.dart';
import 'managed_user.dart';

class _Data {
  _Data(this.users, this.outlets);
  final List<ManagedUser> users;
  final List<OutletInfo> outlets;
}

class UsersAdminPage extends ConsumerStatefulWidget {
  const UsersAdminPage({super.key});
  @override
  ConsumerState<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends ConsumerState<UsersAdminPage> {
  String? _filterOutlet; // hanya owner
  late Future<_Data> _future = _load();

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
    final outlets = session.user.role == AppRole.owner
        ? [
            for (final m in await api.get('/outlets') as List<dynamic>)
              OutletInfo.fromJson(m as Map<String, dynamic>),
          ]
        : [if (session.outlet != null) session.outlet!];
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
    final roles = creatableRoles(me);
    final isOwner = me.role == AppRole.owner;
    final username = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController(text: u?.name);
    final position = TextEditingController(text: u?.position);
    var role = (u != null && roles.contains(u.role)) ? u.role : roles.first;
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password awal (min. 8)',
                      ),
                      onChanged: (_) => setS(() {}),
                    ),
                  ],
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    onChanged: (_) => setS(() {}),
                  ),
                  TextField(
                    controller: position,
                    decoration: const InputDecoration(labelText: 'Jabatan'),
                  ),
                  DropdownButtonFormField<AppRole>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [
                      for (final r in roles)
                        DropdownMenuItem(value: r, child: Text(roleLabel(r))),
                    ],
                    onChanged: (v) => setS(() => role = v ?? role),
                  ),
                  if (isOwner)
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
                        'role': role.name,
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
    final isOwner = ref.read(sessionProvider).value!.user.role == AppRole.owner;
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
    final isOwner = ref.read(sessionProvider).value!.user.role == AppRole.owner;
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
              title: Text(u.name),
              subtitle: Text('${u.username} • ${roleLabel(u.role)}'),
            ),
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

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: d.outlets.isEmpty ? null : () => _create(d.outlets),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Pengguna'),
            ),
            body: Column(
              children: [
                if (me.role == AppRole.owner)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: DropdownButtonFormField<String?>(
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
                  ),
                Expanded(
                  child: d.users.isEmpty
                      ? const Center(child: Text('Belum ada pengguna'))
                      : ListView(
                          children: [
                            for (final u in d.users)
                              ListTile(
                                leading: Icon(
                                  u.active
                                      ? Icons.person_outline
                                      : Icons.person_off_outlined,
                                ),
                                title: Text(
                                  '${u.name}${u.active ? '' : ' (nonaktif)'}',
                                ),
                                subtitle: Text(
                                  '${u.username} • ${roleLabel(u.role)} • ${outletName(u.outletId)}',
                                ),
                                onTap: canManageUser(me, u)
                                    ? () => _actions(u, d.outlets)
                                    : null,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
