import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'printer_service.dart';
import 'printer_settings.dart';
import 'receipt_builder.dart';
import 'receipt_template.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});
  @override
  ConsumerState<PrinterSettingsPage> createState() =>
      _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  PrinterSettings _s = const PrinterSettings();
  bool _loaded = false;
  bool _saving = false;
  ReceiptTemplate? _tpl; // isi struk dari server (null = offline & belum pernah diambil)
  bool _fromLocal = false; // isi struk masih dari perangkat ini, belum tersimpan di server
  final _ip = TextEditingController();
  final _port = TextEditingController();
  final _cols = TextEditingController();
  final _shop = TextEditingController();
  final _addr = TextEditingController();
  final _phone = TextEditingController();
  final _footer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(printerSettingsProvider.future);
    final notifier = ref.read(receiptTemplateProvider.notifier);
    await ref.read(receiptTemplateProvider.future);
    await notifier.refresh(); // pastikan isi terbaru dari server
    final t = ref.read(receiptTemplateProvider).value;
    if (!mounted) return;
    final useLocal = t == null || (!t.configured && hasLegacyLocalContent(s));
    setState(() {
      _s = s;
      _tpl = t;
      _fromLocal = useLocal && hasLegacyLocalContent(s);
      _loaded = true;
      _ip.text = s.lanHost;
      _port.text = '${s.lanPort}';
      _cols.text = '${s.customCols}';
      _shop.text = useLocal || t == null ? s.shopName : t.header;
      _addr.text = useLocal || t == null ? s.shopAddress : t.address;
      _phone.text = useLocal || t == null ? s.shopPhone : t.phone;
      _footer.text = useLocal || t == null ? s.footer : t.footer;
    });
  }

  @override
  void dispose() {
    for (final c in [_ip, _port, _cols, _shop, _addr, _phone, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canEditContent {
    final u = ref.read(appUserProvider).value;
    return u != null && (u.isOwner || u.can('receipt.update'));
  }

  /// Pengaturan perangkat + isi struk di formulir (untuk pratinjau & tes cetak).
  PrinterSettings _collect() => _s.copyWith(
    lanHost: _ip.text.trim(),
    lanPort: int.tryParse(_port.text) ?? 9100,
    customCols: int.tryParse(_cols.text) ?? 32,
    shopName: _shop.text.trim(),
    shopAddress: _addr.text.trim(),
    shopPhone: _phone.text.trim(),
    footer: _footer.text.trim(),
  );

  bool get _contentChanged {
    final t = _tpl;
    if (t == null || _fromLocal || !t.configured) return true;
    return _shop.text.trim() != t.header ||
        _addr.text.trim() != t.address ||
        _phone.text.trim() != t.phone ||
        _footer.text.trim() != t.footer;
  }

  void _upd(PrinterSettings Function(PrinterSettings) f) =>
      setState(() => _s = f(_collect()));

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickBt() async {
    try {
      final list = await pairedPrinters();
      if (!mounted) return;
      if (list.isEmpty) {
        _toast(
          'Belum ada perangkat terpasang. Pairing printer dulu di '
          'pengaturan Bluetooth HP.',
        );
        return;
      }
      final p = await showAppDialog<({String name, String mac})>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Pilih printer'),
          children: [
            for (final d in list)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d),
                child: Text('${d.name}\n${d.mac}'),
              ),
          ],
        ),
      );
      if (p != null) _upd((s) => s.copyWith(btName: p.name, btAddress: p.mac));
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _save() async {
    if (_canEditContent && _shop.text.trim().isEmpty) {
      _toast('Nama di struk wajib diisi');
      return;
    }
    setState(() => _saving = true);
    try {
      // pengaturan printer: hanya di perangkat ini
      await ref.read(printerSettingsProvider.notifier).save(_collect());
      // isi struk: di server, untuk semua perangkat outlet ini
      if (_canEditContent && _contentChanged) {
        try {
          final t = await ref
              .read(receiptTemplateProvider.notifier)
              .save(
                header: _shop.text.trim(),
                address: _addr.text.trim(),
                phone: _phone.text.trim(),
                footer: _footer.text.trim(),
              );
          if (mounted) {
            setState(() {
              _tpl = t;
              _fromLocal = false;
            });
          }
        } catch (e) {
          _toast(
            'Pengaturan printer tersimpan, tetapi isi struk gagal disimpan ke server: '
            '${errorText(e)}',
          );
          return;
        }
      }
      _toast('Tersimpan');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final s = _collect();
    await ref
        .read(printerSettingsProvider.notifier)
        .save(_s.copyWith(lanHost: s.lanHost, lanPort: s.lanPort, customCols: s.customCols));
    try {
      await printLines(s, testLines(s));
    } catch (e) {
      _toast('Gagal cetak: $e');
    }
  }

  Widget _paper(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: .06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.35,
          color: AppColors.ink,
        ),
      ),
    ),
  );

  Widget _actions() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _test,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Tes cetak'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const AppLoadingScreen();
    }
    final cur = _collect();
    final preview = testLines(cur).map((l) => l.text).join('\n');

    final paperCard = SectionCard(
      title: 'Lebar kertas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<PaperWidth>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: PaperWidth.mm58, label: Text('58 mm')),
              ButtonSegment(value: PaperWidth.mm80, label: Text('80 mm')),
              ButtonSegment(value: PaperWidth.custom, label: Text('Kustom')),
            ],
            selected: {_s.paper},
            onSelectionChanged: (v) => _upd((s) => s.copyWith(paper: v.first)),
          ),
          if (_s.paper == PaperWidth.custom) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cols,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Karakter per baris (20–80)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );

    final connectionCard = SectionCard(
      title: 'Koneksi printer',
      child: kIsWeb
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Di web, struk dicetak lewat dialog print browser (PDF).',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<PrinterType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: PrinterType.none,
                      label: Text('Nonaktif'),
                    ),
                    ButtonSegment(
                      value: PrinterType.bluetooth,
                      label: Text('Bluetooth'),
                    ),
                    ButtonSegment(
                      value: PrinterType.lan,
                      label: Text('LAN/WiFi'),
                    ),
                  ],
                  selected: {_s.type},
                  onSelectionChanged: (v) =>
                      _upd((s) => s.copyWith(type: v.first)),
                ),
                if (_s.type == PrinterType.bluetooth) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bluetooth, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _s.btName.isEmpty ? 'Belum dipilih' : _s.btName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_s.btAddress.isNotEmpty)
                                Text(
                                  _s.btAddress,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: _pickBt,
                          child: const Text('Pilih'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_s.type == PrinterType.lan) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ip,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'IP printer',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Port'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );

    final canEdit = _canEditContent;
    final outletName = ref.watch(activeOutletProvider)?.name;
    final (noteIcon, noteColor, noteText) = _tpl == null
        ? (
            Icons.cloud_off_outlined,
            AppColors.warning,
            'Isi struk belum bisa diambil dari server (offline). Yang tampil adalah isi '
                'yang tersimpan di perangkat ini.',
          )
        : _fromLocal
        ? (
            Icons.info_outline,
            AppColors.primary,
            canEdit
                ? 'Isi struk ini masih tersimpan di perangkat ini saja. Tekan "Simpan" agar '
                      'tersimpan di server dan dipakai semua perangkat outlet.'
                : 'Isi struk ini masih tersimpan di perangkat ini saja. Minta owner atau '
                      'manager menyimpannya agar dipakai semua perangkat outlet.',
          )
        : (
            Icons.cloud_done_outlined,
            AppColors.success,
            canEdit
                ? 'Tersimpan di server untuk outlet ${outletName ?? 'ini'}. Perubahan berlaku '
                      'di semua perangkat outlet.'
                : 'Diatur oleh owner/manager untuk outlet ${outletName ?? 'ini'} dan berlaku '
                      'di semua perangkat outlet.',
          );
    final contentCard = SectionCard(
      title: 'Isi struk',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: noteColor.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(noteIcon, size: 18, color: noteColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(noteText, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shop,
            readOnly: !canEdit,
            decoration: const InputDecoration(labelText: 'Nama di struk'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addr,
            readOnly: !canEdit,
            decoration: const InputDecoration(labelText: 'Alamat'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            readOnly: !canEdit,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telepon (opsional)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            readOnly: !canEdit,
            decoration: const InputDecoration(labelText: 'Pesan penutup (footer)'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );

    final behaviorCard = SectionCard(
      title: 'Akhir struk',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Printer punya pemotong kertas otomatis'),
            subtitle: const Text('Matikan untuk printer thermal kecil yang kertasnya disobek manual.'),
            value: _s.autoCut,
            onChanged: (v) => _upd((s) => s.copyWith(autoCut: v)),
          ),
          if (!_s.autoCut) ...[
            const SizedBox(height: 4),
            Text(
              'Jarak kosong sebelum disobek: ${_s.feedLines} baris',
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _s.feedLines.toDouble(),
              min: 0,
              max: 8,
              divisions: 8,
              label: '${_s.feedLines}',
              onChanged: (v) => _upd((s) => s.copyWith(feedLines: v.round())),
            ),
            Text(
              'Kecilkan bila sisa kertas kosong terlalu panjang; besarkan bila baris terakhir '
              'ikut tersobek. Coba dengan "Tes cetak".',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );

    final previewCard = SectionCard(
      title: 'Pratinjau (${cur.cols} kolom)',
      child: _paper(preview),
    );

    return Scaffold(
      appBar: RmsAppBar(title: const Text('Printer & Struk')),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final settings = [contentCard, paperCard, connectionCard, behaviorCard];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final w in settings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w,
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    children: [
                      previewCard,
                      const SizedBox(height: 12),
                      _actions(),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final w in [...settings, previewCard])
                Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 900
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(top: false, child: _actions()),
            ),
    );
  }
}
