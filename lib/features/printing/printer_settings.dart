import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_controller.dart';

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
    this.shopName = 'Nama Outlet',
    this.shopAddress = '',
    this.footer = 'Terima kasih',
  });

  final PrinterType type;
  final PaperWidth paper;
  final int customCols;
  final String btAddress;
  final String btName;
  final String lanHost;
  final int lanPort;
  final bool autoPrint;
  final String shopName;
  final String shopAddress;
  final String footer;

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
    String? shopName,
    String? shopAddress,
    String? footer,
  }) => PrinterSettings(
    type: type ?? this.type,
    paper: paper ?? this.paper,
    customCols: customCols ?? this.customCols,
    btAddress: btAddress ?? this.btAddress,
    btName: btName ?? this.btName,
    lanHost: lanHost ?? this.lanHost,
    lanPort: lanPort ?? this.lanPort,
    autoPrint: autoPrint ?? this.autoPrint,
    shopName: shopName ?? this.shopName,
    shopAddress: shopAddress ?? this.shopAddress,
    footer: footer ?? this.footer,
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
    shopName: m['shopName'] as String? ?? 'Nama Outlet',
    shopAddress: m['shopAddress'] as String? ?? '',
    footer: m['footer'] as String? ?? 'Terima kasih',
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
    'shopName': shopName,
    'shopAddress': shopAddress,
    'footer': footer,
  };
}

/// Disimpan lokal per device (collection `device_settings`, dirty=false
/// sehingga tidak pernah dikirim ke Firestore).
class PrinterSettingsNotifier extends AsyncNotifier<PrinterSettings> {
  @override
  Future<PrinterSettings> build() async {
    final row = await ref
        .read(databaseProvider)
        .find('device_settings', 'printer');
    if (row == null) return const PrinterSettings();
    return PrinterSettings.fromMap(
      jsonDecode(row.json) as Map<String, dynamic>,
    );
  }

  Future<void> save(PrinterSettings s) async {
    await ref
        .read(databaseProvider)
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
