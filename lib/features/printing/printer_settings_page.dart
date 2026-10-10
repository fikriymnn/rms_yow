import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cur = _collect();
    final th = Theme.of(context).textTheme;
    final preview = testLines(cur).map((l) => l.text).join('\n');

    return Scaffold(
      appBar: AppBar(title: const Text('Printer & Struk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Lebar kertas', style: th.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<PaperWidth>(
            segments: const [
              ButtonSegment(value: PaperWidth.mm58, label: Text('58 mm')),
              ButtonSegment(value: PaperWidth.mm80, label: Text('80 mm')),
              ButtonSegment(value: PaperWidth.custom, label: Text('Kustom')),
            ],
            selected: {_s.paper},
            onSelectionChanged: (v) => _upd((s) => s.copyWith(paper: v.first)),
          ),
          if (_s.paper == PaperWidth.custom)
            TextField(
              controller: _cols,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Karakter per baris (20–80)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 20),
          Text('Koneksi printer', style: th.titleMedium),
          const SizedBox(height: 8),
          if (kIsWeb)
            const Text(
              'Di web, struk dicetak lewat dialog print browser (PDF).',
            )
          else ...[
            SegmentedButton<PrinterType>(
              segments: const [
                ButtonSegment(value: PrinterType.none, label: Text('Nonaktif')),
                ButtonSegment(
                  value: PrinterType.bluetooth,
                  label: Text('Bluetooth'),
                ),
                ButtonSegment(value: PrinterType.lan, label: Text('LAN/WiFi')),
              ],
              selected: {_s.type},
              onSelectionChanged: (v) => _upd((s) => s.copyWith(type: v.first)),
            ),
            if (_s.type == PrinterType.bluetooth)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_s.btName.isEmpty ? 'Belum dipilih' : _s.btName),
                subtitle: Text(_s.btAddress),
                trailing: FilledButton.tonal(
                  onPressed: _pickBt,
                  child: const Text('Pilih'),
                ),
              ),
            if (_s.type == PrinterType.lan)
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
          const SizedBox(height: 20),
          Text('Isi struk', style: th.titleMedium),
          TextField(
            controller: _shop,
            decoration: const InputDecoration(labelText: 'Nama outlet'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _addr,
            decoration: const InputDecoration(labelText: 'Alamat'),
          ),
          TextField(
            controller: _footer,
            decoration: const InputDecoration(labelText: 'Footer'),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cetak otomatis setelah pembayaran'),
            value: _s.autoPrint,
            onChanged: (v) => _upd((s) => s.copyWith(autoPrint: v)),
          ),
          const SizedBox(height: 8),
          Text('Pratinjau (${cur.cols} kolom)', style: th.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                preview,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _test,
                  child: const Text('Tes cetak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
