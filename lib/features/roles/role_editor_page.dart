import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'role_models.dart';
import 'role_providers.dart';

final _keyRe = RegExp(r'^[a-z][a-z0-9_]{1,19}$');

/// "Kepala Bar" -> "kepala_bar" (maks. 20 karakter, diawali huruf).
String slugifyRoleKey(String name) {
  var s = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (s.isNotEmpty && !RegExp(r'^[a-z]').hasMatch(s)) s = 'r_$s';
  return s.length > 20 ? s.substring(0, 20) : s;
}

class RoleEditorPage extends ConsumerStatefulWidget {
  const RoleEditorPage({super.key, this.role});
  final RoleInfo? role; // null = role baru

  @override
  ConsumerState<RoleEditorPage> createState() => _RoleEditorPageState();
}

class _RoleEditorPageState extends ConsumerState<RoleEditorPage> {
  late final _name = TextEditingController(text: widget.role?.name);
  late final _key = TextEditingController(text: widget.role?.key);
  late final _desc = TextEditingController(text: widget.role?.description);
  late bool _isStaff = widget.role?.isStaff ?? false;
  late final Set<String> _perms = {...?widget.role?.permissions};
  bool _keyTouched = false;
  bool _saving = false;

  bool get _isNew => widget.role == null;
  bool get _readOnly => widget.role?.locked ?? false;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  bool get _valid =>
      _name.text.trim().length >= 2 && (!_isNew || _keyRe.hasMatch(_key.text));

  // Mengaktifkan aksi apa pun ikut mengaktifkan "Lihat" pada fitur itu;
  // mematikan "Lihat" mematikan seluruh aksi fitur tersebut.
  void _toggle(PermFeature f, PermAction a, bool on) {
    final read = '${f.key}.read';
    final hasRead = f.actions.any((x) => x.permission == read);
    setState(() {
      if (on) {
        _perms.add(a.permission);
        if (hasRead) _perms.add(read);
      } else {
        _perms.remove(a.permission);
        if (a.permission == read) {
          _perms.removeAll(f.actions.map((x) => x.permission));
        }
      }
    });
  }

  void _toggleAll(PermFeature f, bool on) => setState(() {
    final all = f.actions.map((x) => x.permission);
    on ? _perms.addAll(all) : _perms.removeAll(all);
  });

  Future<bool> _confirm(String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _saving = true);
    try {
      await job();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() {
    final repo = ref.read(roleRepositoryProvider);
    return _run(
      () => _isNew
          ? repo.create(
              key: _key.text,
              name: _name.text.trim(),
              description: _desc.text.trim(),
              isStaff: _isStaff,
              permissions: _perms,
            )
          : repo.update(
              widget.role!.key,
              name: _name.text.trim(),
              description: _desc.text.trim(),
              isStaff: _isStaff,
              permissions: _perms,
            ),
    );
  }

  Future<void> _reset() async {
    final ok = await _confirm(
      'Kembalikan ke bawaan?',
      'Nama dan seluruh izin role ini dikembalikan ke pengaturan awal aplikasi.',
      'Kembalikan',
    );
    if (ok)
      await _run(
        () => ref.read(roleRepositoryProvider).reset(widget.role!.key),
      );
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      'Hapus role?',
      'Role "${widget.role!.name}" dihapus permanen. Role yang masih dipakai pengguna tidak bisa dihapus.',
      'Hapus',
    );
    if (ok)
      await _run(
        () => ref.read(roleRepositoryProvider).delete(widget.role!.key),
      );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(roleCatalogProvider);
    final role = widget.role;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Role baru' : role!.name),
        actions: [
          if (!_isNew && !_readOnly)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'reset' ? _reset() : _delete(),
              itemBuilder: (_) => [
                if (role!.isSystem)
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Kembalikan ke bawaan'),
                  ),
                if (!role.isSystem)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus role'),
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: _readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: (_valid && !_saving) ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_readOnly)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StatusPill(
                    'Owner selalu punya akses penuh dan tidak bisa diubah',
                    tone: Tone.success,
                  ),
                ),
              SectionCard(
                title: 'Informasi role',
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      enabled: !_readOnly,
                      decoration: const InputDecoration(labelText: 'Nama role'),
                      onChanged: (v) => setState(() {
                        if (_isNew && !_keyTouched)
                          _key.text = slugifyRoleKey(v);
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _key,
                      enabled: _isNew,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Kode role',
                        helperText: _isNew
                            ? 'Huruf kecil/angka/_ , 2-20 karakter. Tidak bisa diubah lagi.'
                            : null,
                        errorText:
                            _isNew &&
                                _key.text.isNotEmpty &&
                                !_keyRe.hasMatch(_key.text)
                            ? 'Format kode tidak valid'
                            : null,
                      ),
                      onChanged: (_) => setState(() => _keyTouched = true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _desc,
                      enabled: !_readOnly,
                      decoration: const InputDecoration(labelText: 'Deskripsi'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dikelola manager outlet'),
                      subtitle: const Text(
                        'Manager boleh membuat dan mengubah akun dengan role ini.',
                      ),
                      value: _isStaff,
                      onChanged: _readOnly
                          ? null
                          : (v) => setState(() => _isStaff = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hak akses',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusPill('${_perms.length} izin aktif', tone: Tone.info),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih aksi yang boleh dilakukan role ini pada tiap fitur. '
                'Perubahan berlaku otomatis di perangkat pengguna dalam sekitar 1 menit.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(errorText(e)),
                data: _matrix,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _matrix(List<PermFeature> features) {
    final groups = <String, List<PermFeature>>{};
    for (final f in features) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              g.key.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          for (final f in g.value) _featureCard(f),
        ],
      ],
    );
  }

  Widget _featureCard(PermFeature f) {
    final all = f.actions.every((a) => _perms.contains(a.permission));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!_readOnly)
                TextButton(
                  onPressed: () => _toggleAll(f, !all),
                  child: Text(all ? 'Kosongkan' : 'Semua'),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final a in f.actions)
                FilterChip(
                  label: Text(a.label),
                  selected: _perms.contains(a.permission),
                  onSelected: _readOnly ? null : (v) => _toggle(f, a, v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
