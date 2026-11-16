import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/db/meta_db.dart';
import '../auth/auth_providers.dart';
import 'printer_settings.dart';

/// Isi struk per outlet (nama, alamat, telepon, footer). Disimpan di server sehingga
/// semua perangkat outlet memakai isi yang sama; salinan terakhir disimpan di perangkat
/// agar tetap bisa mencetak saat offline.
class ReceiptTemplate {
  const ReceiptTemplate({
    required this.outletId,
    required this.header,
    this.address = '',
    this.phone = '',
    this.footer = '',
    this.configured = false,
    this.updatedAt,
  });

  final String outletId;
  final String header;
  final String address;
  final String phone;
  final String footer;

  /// false = belum pernah diatur di server (isi masih bawaan dari data outlet).
  final bool configured;
  final int? updatedAt;

  factory ReceiptTemplate.fromJson(Map<String, dynamic> m) => ReceiptTemplate(
    outletId: m['outlet_id'] as String? ?? '',
    header: m['header'] as String? ?? '',
    address: m['address'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    footer: m['footer'] as String? ?? '',
    configured: m['configured'] as bool? ?? false,
    updatedAt: (m['updated_at'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'outlet_id': outletId,
    'header': header,
    'address': address,
    'phone': phone,
    'footer': footer,
    'configured': configured,
    'updated_at': updatedAt,
  };
}

String _cacheKey(String outletId) => 'receipt_tpl_$outletId';

class ReceiptTemplateNotifier extends AsyncNotifier<ReceiptTemplate?> {
  @override
  Future<ReceiptTemplate?> build() async {
    final outletId = ref.watch(activeOutletIdProvider);
    if (outletId == null) return null;
    final m = await ref.read(metaDbProvider).getMeta(_cacheKey(outletId));
    final cached = m == null ? null : ReceiptTemplate.fromJson(m);
    if (cached != null) {
      unawaited(refresh()); // pakai salinan dulu, perbarui dari server di belakang
      return cached;
    }
    try {
      return await _fetch(outletId);
    } catch (_) {
      return null; // offline & belum pernah diambil: pakai isi lokal lama / bawaan
    }
  }

  Future<ReceiptTemplate> _fetch(String outletId) async {
    final res = await ref.read(apiClientProvider).get('/receipt-template/$outletId');
    final t = ReceiptTemplate.fromJson(Map<String, dynamic>.from(res as Map));
    await ref.read(metaDbProvider).putMeta(_cacheKey(outletId), t.toJson());
    return t;
  }

  /// Ambil isi terbaru dari server. Gagal (offline) = tetap pakai salinan.
  Future<void> refresh() async {
    final outletId = ref.read(activeOutletIdProvider);
    if (outletId == null) return;
    try {
      final t = await _fetch(outletId);
      if (ref.read(activeOutletIdProvider) == outletId) state = AsyncData(t);
    } catch (_) {
      // offline
    }
  }

  /// Simpan ke server (butuh izin `receipt.update`).
  Future<ReceiptTemplate> save({
    required String header,
    required String address,
    required String phone,
    required String footer,
  }) async {
    final outletId = ref.read(activeOutletIdProvider);
    if (outletId == null) throw StateError('Outlet belum dipilih');
    final res = await ref.read(apiClientProvider).put(
      '/receipt-template/$outletId',
      data: {'header': header, 'address': address, 'phone': phone, 'footer': footer},
    );
    final t = ReceiptTemplate.fromJson(Map<String, dynamic>.from(res as Map));
    await ref.read(metaDbProvider).putMeta(_cacheKey(outletId), t.toJson());
    state = AsyncData(t);
    return t;
  }
}

final receiptTemplateProvider =
    AsyncNotifierProvider<ReceiptTemplateNotifier, ReceiptTemplate?>(
      ReceiptTemplateNotifier.new,
    );

/// Isi lokal lama (sebelum template disimpan di server) masih dipakai bila outlet
/// belum mengatur template di server dan perangkat ini pernah mengisinya.
bool hasLegacyLocalContent(PrinterSettings s) =>
    s.shopName.trim().isNotEmpty && s.shopName != const PrinterSettings().shopName;

/// Pengaturan printer perangkat + isi struk outlet. Dipakai saat mencetak.
PrinterSettings mergeReceipt(PrinterSettings s, ReceiptTemplate? t) {
  if (t == null || (!t.configured && hasLegacyLocalContent(s))) return s;
  return s.copyWith(
    shopName: t.header,
    shopAddress: t.address,
    shopPhone: t.phone,
    footer: t.footer,
  );
}

final effectivePrinterSettingsProvider = Provider<PrinterSettings?>((ref) {
  final s = ref.watch(printerSettingsProvider).value;
  if (s == null) return null;
  return mergeReceipt(s, ref.watch(receiptTemplateProvider).value);
});
