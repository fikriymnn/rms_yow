import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../help/help_page.dart';
import 'role_models.dart';
import 'role_providers.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

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
  String? _template; // role baru: null = Custom

  /// Isi form dari template; Custom mengosongkan izin. Izin tetap bisa diubah sesudahnya.
  void _applyTemplate(RoleTemplate? t, List<RoleInfo> existing) {
    final prev = _template;
    setState(() {
      _template = t?.key;
      final fromPrevTemplate = prev != null;
      if (t == null) {
        if (fromPrevTemplate) {
          _name.clear();
          _desc.clear();
          if (!_keyTouched) _key.clear();
        }
        _perms.clear();
        _isStaff = false;
        return;
      }
      _name.text = t.name;
      _desc.text = t.description;
      _isStaff = t.isStaff;
      _perms
        ..clear()
        ..addAll(t.permissions);
      if (!_keyTouched) {
        final taken = existing.map((r) => r.key).toSet();
        _key.text = taken.contains(t.key) ? slugifyRoleKey('${t.name} 2') : t.key;
      }
    });
  }

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
    final r = await showAppDialog<bool>(
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
      'Kembalikan ke template?',
      'Nama, deskripsi, dan seluruh izin role ini dikembalikan ke template aplikasi.',
      'Kembalikan',
    );
    if (ok)
      await _run(
        () => ref.read(roleRepositoryProvider).reset(widget.role!.key),
      );
  }

  Future<void> _delete() async {
    final r = widget.role!;
    if (r.userCount > 0) {
      await showAppDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Role masih dipakai'),
          content: Text(
            'Role "${r.name}" dipakai ${r.userCount} pengguna. Pindahkan mereka ke role lain '
            'di Data Master → Pengguna, lalu hapus role ini.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }
    final ok = await _confirm(
      'Hapus role?',
      'Role "${r.name}" dihapus permanen dan tidak bisa dipilih lagi untuk pengguna. '
          '${r.isSystem ? 'Role bawaan ini bisa dibuat lagi kapan saja dari template di form Role baru.' : ''}',
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
    final templates = ref.watch(roleTemplatesProvider).value ?? const <RoleTemplate>[];
    final existing = ref.watch(rolesProvider).value ?? const <RoleInfo>[];
    final role = widget.role;
    final fromTemplate = role != null && templates.any((t) => t.key == role.key);
    return Scaffold(
      appBar: RmsAppBar(
        title: Text(_isNew ? 'Role baru' : role!.name),
        actions: [
          if (!_isNew && !_readOnly)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'reset' ? _reset() : _delete(),
              itemBuilder: (_) => [
                if (fromTemplate)
                  const PopupMenuItem(
                    value: 'reset',
                    child: ListTile(
                      leading: Icon(Icons.restart_alt_rounded),
                      title: Text('Kembalikan ke template'),
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text('Hapus role', style: TextStyle(color: AppColors.danger)),
                  ),
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
              if (_isNew) ...[
                _templatePicker(templates, existing),
                const SizedBox(height: 16),
              ],
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusPill('${_perms.length} izin aktif', tone: Tone.info),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Buka tiap fitur lalu centang aksi yang boleh dilakukan role ini. Setiap aksi ada '
                'penjelasan singkatnya. Perubahan berlaku di perangkat pengguna dalam sekitar 1 menit.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Material(
                color: AppColors.sageSoft,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const HelpPage(initialTopic: 'roles'),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_outlined, color: AppColors.sageInk),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bingung memilih? Baca panduan hak akses, termasuk beda '
                            '"Menyetujui tingkat 1" dan "Menyetujui akhir".',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sageInk,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.sageInk),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: AppLoader()),
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

  Widget _templatePicker(List<RoleTemplate> templates, List<RoleInfo> existing) {
    Widget option({
      required String label,
      required String sub,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
    }) => Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.ink : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? Colors.white : AppColors.ink),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.35,
                color: selected ? AppColors.onInkMuted : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih template hak akses',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Isi otomatis dari template, atau pilih Custom untuk mengatur sendiri. '
          'Centang dari template tetap bisa diubah sebelum disimpan.',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              option(
                label: 'Custom',
                sub: 'Kosong, atur izin sendiri',
                icon: Icons.tune_rounded,
                selected: _template == null,
                onTap: () => _applyTemplate(null, existing),
              ),
              for (final t in templates) ...[
                const SizedBox(width: 10),
                option(
                  label: t.name,
                  sub: '${t.permissions.length} izin · ${t.description}',
                  selected: _template == t.key,
                  onTap: () => _applyTemplate(t, existing),
                ),
              ],
            ],
          ),
        ),
      ],
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
              style: GoogleFonts.plusJakartaSans(
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
    final on = f.actions.where((a) => _perms.contains(a.permission)).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on > 0 ? AppColors.ink : AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 8, 10),
          initiallyExpanded: f.key == 'approvals',
          title: Text(
            f.label,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              f.description.isEmpty ? '$on dari ${f.actions.length} aksi aktif' : f.description,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4, color: AppColors.muted),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusPill('$on/${f.actions.length}', tone: on > 0 ? Tone.info : Tone.neutral),
              if (!_readOnly)
                TextButton(
                  onPressed: () => _toggleAll(f, !all),
                  child: Text(all ? 'Kosongkan' : 'Semua'),
                ),
            ],
          ),
          children: [
            for (final a in f.actions) _actionRow(f, a),
          ],
        ),
      ),
    );
  }

  /// Satu izin: kotak centang + nama + petunjuk kegunaannya.
  Widget _actionRow(PermFeature f, PermAction a) {
    final checked = _perms.contains(a.permission);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _readOnly ? null : () => _toggle(f, a, !checked),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: _readOnly ? null : (v) => _toggle(f, a, v ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.label,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (a.help.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.help,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
