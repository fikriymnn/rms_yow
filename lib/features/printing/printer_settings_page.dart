import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'printer_service.dart';
import 'printer_settings.dart';
import 'receipt_builder.dart';

class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});
  @override
  ConsumerState<PrinterSettingsPage> createState() =>
      _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  PrinterSettings _s = const PrinterSettings();
  bool _loaded = false;
  final _ip = TextEditingController();
  final _port = TextEditingController();
  final _cols = TextEditingController();
  final _shop = TextEditingController();
  final _addr = TextEditingController();
  final _footer = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(printerSettingsProvider.future).then((s) {
      if (!mounted) return;
      setState(() {
        _s = s;
        _loaded = true;
        _ip.text = s.lanHost;
        _port.text = '${s.lanPort}';
        _cols.text = '${s.customCols}';
        _shop.text = s.shopName;
        _addr.text = s.shopAddress;
        _footer.text = s.footer;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_ip, _port, _cols, _shop, _addr, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  PrinterSettings _collect() => _s.copyWith(
    lanHost: _ip.text.trim(),
    lanPort: int.tryParse(_port.text) ?? 9100,
    customCols: int.tryParse(_cols.text) ?? 32,
    shopName: _shop.text.trim(),
    shopAddress: _addr.text.trim(),
    footer: _footer.text.trim(),
  );

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
      final p = await showDialog<({String name, String mac})>(
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
    await ref.read(printerSettingsProvider.notifier).save(_collect());
    _toast('Tersimpan');
  }

  Future<void> _test() async {
    final s = _collect();
    await ref.read(printerSettingsProvider.notifier).save(s);
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
        style: const TextStyle(
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
        child: FilledButton(onPressed: _save, child: const Text('Simpan')),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Di web, struk dicetak lewat dialog print browser (PDF).',
                      style: GoogleFonts.inter(fontSize: 13),
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
                        const Icon(Icons.bluetooth, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _s.btName.isEmpty ? 'Belum dipilih' : _s.btName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_s.btAddress.isNotEmpty)
                                Text(
                                  _s.btAddress,
                                  style: GoogleFonts.inter(
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

    final contentCard = SectionCard(
      title: 'Isi struk',
      child: Column(
        children: [
          TextField(
            controller: _shop,
            decoration: const InputDecoration(labelText: 'Nama outlet'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addr,
            decoration: const InputDecoration(labelText: 'Alamat'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footer,
            decoration: const InputDecoration(labelText: 'Footer'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cetak otomatis setelah pembayaran'),
            value: _s.autoPrint,
            onChanged: (v) => _upd((s) => s.copyWith(autoPrint: v)),
          ),
        ],
      ),
    );

    final previewCard = SectionCard(
      title: 'Pratinjau (${cur.cols} kolom)',
      child: _paper(preview),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Printer & Struk')),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final settings = [paperCard, connectionCard, contentCard];
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
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(top: false, child: _actions()),
            ),
    );
  }
}
