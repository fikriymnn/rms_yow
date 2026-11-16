import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/meta_db.dart';

enum PrinterType { none, bluetooth, lan }

enum PaperWidth { mm58, mm80, custom }

class PrinterSettings {
  const PrinterSettings({
    this.type = PrinterType.none,
    this.paper = PaperWidth.mm58,
    this.customCols = 32,
    this.btAddress = '',
    this.btName = '',
    this.lanHost = '',
    this.lanPort = 9100,
    this.autoPrint = false,
    this.kitchenSlip = true,
    this.shopName = 'Nama Outlet',
    this.shopAddress = '',
    this.shopPhone = '',
    this.footer = 'Terima kasih',
    this.feedLines = 3,
    this.autoCut = false,
  });

  final PrinterType type;
  final PaperWidth paper;
  final int customCols;
  final String btAddress;
  final String btName;
  final String lanHost;
  final int lanPort;
  final bool autoPrint; // tidak dipakai lagi: cetak lewat popup setelah bayar
  final bool kitchenSlip; // tidak dipakai lagi: tombol "Cetak struk dapur" di popup
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String footer;

  /// Baris kosong setelah struk agar bagian akhir melewati sisi sobek printer (0–8).
  final int feedLines;

  /// Printer punya pemotong kertas otomatis.
  final bool autoCut;

  /// Karakter per baris: 58mm = 32, 80mm = 48, atau kustom.
  int get cols => switch (paper) {
    PaperWidth.mm58 => 32,
    PaperWidth.mm80 => 48,
    PaperWidth.custom => customCols.clamp(20, 80).toInt(),
  };

  PrinterSettings copyWith({
    PrinterType? type,
    PaperWidth? paper,
    int? customCols,
    String? btAddress,
    String? btName,
    String? lanHost,
    int? lanPort,
    bool? autoPrint,
    bool? kitchenSlip,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? footer,
    int? feedLines,
    bool? autoCut,
  }) => PrinterSettings(
    type: type ?? this.type,
    paper: paper ?? this.paper,
    customCols: customCols ?? this.customCols,
    btAddress: btAddress ?? this.btAddress,
    btName: btName ?? this.btName,
    lanHost: lanHost ?? this.lanHost,
    lanPort: lanPort ?? this.lanPort,
    autoPrint: autoPrint ?? this.autoPrint,
    kitchenSlip: kitchenSlip ?? this.kitchenSlip,
    shopName: shopName ?? this.shopName,
    shopAddress: shopAddress ?? this.shopAddress,
    shopPhone: shopPhone ?? this.shopPhone,
    footer: footer ?? this.footer,
    feedLines: feedLines ?? this.feedLines,
    autoCut: autoCut ?? this.autoCut,
  );

  factory PrinterSettings.fromMap(Map<String, dynamic> m) => PrinterSettings(
    type: PrinterType.values.firstWhere(
      (e) => e.name == m['type'],
      orElse: () => PrinterType.none,
    ),
    paper: PaperWidth.values.firstWhere(
      (e) => e.name == m['paper'],
      orElse: () => PaperWidth.mm58,
    ),
    customCols: (m['customCols'] as num?)?.toInt() ?? 32,
    btAddress: m['btAddress'] as String? ?? '',
    btName: m['btName'] as String? ?? '',
    lanHost: m['lanHost'] as String? ?? '',
    lanPort: (m['lanPort'] as num?)?.toInt() ?? 9100,
    autoPrint: m['autoPrint'] as bool? ?? false,
    kitchenSlip: m['kitchenSlip'] as bool? ?? true,
    shopName: m['shopName'] as String? ?? 'Nama Outlet',
    shopAddress: m['shopAddress'] as String? ?? '',
    shopPhone: m['shopPhone'] as String? ?? '',
    footer: m['footer'] as String? ?? 'Terima kasih',
    feedLines: ((m['feedLines'] as num?)?.toInt() ?? 3).clamp(0, 8).toInt(),
    autoCut: m['autoCut'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'paper': paper.name,
    'customCols': customCols,
    'btAddress': btAddress,
    'btName': btName,
    'lanHost': lanHost,
    'lanPort': lanPort,
    'autoPrint': autoPrint,
    'kitchenSlip': kitchenSlip,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'shopPhone': shopPhone,
    'footer': footer,
    'feedLines': feedLines,
    'autoCut': autoCut,
  };
}

/// Pengaturan printer, disimpan lokal per perangkat (collection `device_settings`, tidak
/// disinkron). Isi struk (nama, alamat, telepon, footer) kini diambil dari server per outlet
/// lewat `receiptTemplateProvider`; `shopName/shopAddress/footer` di sini hanya isi lama
/// perangkat, dipakai sampai outlet mengatur template di server.
class PrinterSettingsNotifier extends AsyncNotifier<PrinterSettings> {
  @override
  Future<PrinterSettings> build() async {
    final row = await ref
        .read(metaDbProvider)
        .find('device_settings', 'printer');
    if (row == null) return const PrinterSettings();
    return PrinterSettings.fromMap(
      jsonDecode(row.json) as Map<String, dynamic>,
    );
  }

  Future<void> save(PrinterSettings s) async {
    await ref
        .read(metaDbProvider)
        .upsert(
          DocsCompanion(
            collection: const Value('device_settings'),
            id: const Value('printer'),
            json: Value(jsonEncode(s.toMap())),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            deleted: const Value(false),
            dirty: const Value(false),
          ),
        );
    state = AsyncData(s);
  }
}

final printerSettingsProvider =
    AsyncNotifierProvider<PrinterSettingsNotifier, PrinterSettings>(
      PrinterSettingsNotifier.new,
    );
